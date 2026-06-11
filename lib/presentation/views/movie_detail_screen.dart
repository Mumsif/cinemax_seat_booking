import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cinemax_seat_booking/core/services/tmdb_service.dart';
import 'package:cinemax_seat_booking/presentation/views/showtime_selection_screen.dart';

class MovieDetailScreen extends StatefulWidget {
  final Map<String, dynamic> movie;
  final String? preselectedCinema;
  final List<String>? preselectedShowTimes;

  const MovieDetailScreen({
    super.key,
    required this.movie,
    this.preselectedCinema,
    this.preselectedShowTimes,
  });

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool get _comingFromTheater => widget.preselectedCinema != null;

  List<Map<String, dynamic>> _availableCinemas = [];
  bool _isLoadingCinemas = true;
  String? _cinemasError;

  String _overview = '';
  bool _isLoadingOverview = false;

  @override
  void initState() {
    super.initState();
    _overview = widget.movie['overview']?.toString() ?? '';
    _loadAvailableCinemas();
    _fetchOverviewIfNeeded();
  }

  Future<void> _fetchOverviewIfNeeded() async {
    final movie = widget.movie;
    final existingOverview = movie['overview']?.toString() ?? '';
    if (existingOverview.isNotEmpty) {
      setState(() {
        _overview = existingOverview;
        _isLoadingOverview = false;
      });
      return;
    }

    final id = movie['id'] ?? movie['movieId'];
    if (id == null) {
      setState(() {
        _overview = 'No description available';
        _isLoadingOverview = false;
      });
      return;
    }

    setState(() {
      _isLoadingOverview = true;
    });

    try {
      final movieId = id is int ? id : int.tryParse(id.toString());
      if (movieId != null) {
        final details = await TmdbService.getMovieDetails(movieId);
        if (details != null && details['overview'] != null) {
          setState(() {
            _overview = details['overview'];
          });
          return;
        }
      }
    } catch (e) {
      print('Error fetching movie overview: $e');
    } finally {
      setState(() {
        _isLoadingOverview = false;
        if (_overview.isEmpty) {
          _overview = movie['overview']?.toString() ?? 'No description available';
        }
      });
    }
  }

  Future<void> _loadAvailableCinemas() async {
    setState(() {
      _isLoadingCinemas = true;
      _cinemasError = null;
    });
    try {
      final rawId = widget.movie['id'] ?? widget.movie['movieId'];
      final movieId = rawId is int ? rawId : (rawId is String ? int.tryParse(rawId) : null);

      if (movieId == null) {
        _availableCinemas = [];
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('movies')
          .where('movieId', isEqualTo: movieId)
          .where('status', isEqualTo: 'active')
          .get();

      // Dedup by cinemaName (a cinema should have at most one active entry per movie)
      final Map<String, Map<String, dynamic>> byCinema = {};
      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        final cname = data['cinemaName'] as String?;
        if (cname != null && !byCinema.containsKey(cname)) {
          data['docId'] = doc.id;
          byCinema[cname] = data;
        }
      }
      _availableCinemas = byCinema.values.toList();
    } catch (e) {
      print('Error loading available cinemas for movie: $e');
      _availableCinemas = [];
      _cinemasError = e.toString().contains('unavailable')
          ? 'Could not load theater information (connection issue).'
          : 'Failed to load available theaters.';
    } finally {
      if (mounted) {
        setState(() => _isLoadingCinemas = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final backdropHeight = screenWidth * 0.6;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Image.network(
                    TmdbService.getImageUrl(
                      widget.movie['backdrop_path'] ?? widget.movie['poster_path'] ?? '',
                    ),
                    height: backdropHeight,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: backdropHeight,
                      color: const Color(0xFF1E1E1E),
                      child: const Center(
                        child: Icon(Icons.movie, color: Colors.grey, size: 60),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 4,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Movie Title
                    Text(
                      widget.movie['title'] ?? 'Unknown Movie',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Duration, Rating, Cinema row
                    Row(
                      children: [
                        if (widget.movie['duration'] != null) ...[
                          const Icon(Icons.schedule, color: Color(0xFFE50914), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.movie['duration']}',
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(width: 16),
                        ],
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.movie['vote_average'] ?? '-'}',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        if (_comingFromTheater) ...[
                          const SizedBox(width: 16),
                          const Icon(Icons.location_on, color: Color(0xFFE50914), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            widget.preselectedCinema!,
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Description Section
                    const Text(
                      "Synopsis",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingOverview)
                      const SizedBox(
                        height: 20,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFE50914),
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    else
                      Text(
                        _overview.isNotEmpty ? _overview : (widget.movie['overview']?.toString() ?? 'No description available'),
                        style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
                      ),
                    const SizedBox(height: 24),

                    // FROM HOME / SEARCH: Dynamically show only theaters where this movie is active (from Firestore)
                    if (!_comingFromTheater) ...[
                      const Text(
                        "Available Theaters",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingCinemas)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              color: Color(0xFFE50914),
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      else if (_cinemasError != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.wifi_off, color: Colors.grey, size: 36),
                              const SizedBox(height: 12),
                              Text(
                                _cinemasError!,
                                style: const TextStyle(color: Colors.grey, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _loadAvailableCinemas,
                                child: const Text('Retry', style: TextStyle(color: Color(0xFFE50914))),
                              ),
                            ],
                          ),
                        )
                      else if (_availableCinemas.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.movie_outlined, color: Colors.grey.withOpacity(0.6), size: 40),
                              const SizedBox(height: 12),
                              Text(
                                'No theaters showing this movie',
                                style: TextStyle(
                                  color: Colors.grey.withOpacity(0.8),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'This movie is not currently scheduled in any of our cinemas.',
                                style: TextStyle(color: Colors.grey.withOpacity(0.6), fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: _availableCinemas.map((cinemaData) {
                            final theaterName = cinemaData['cinemaName'] as String? ?? 'Unknown';
                            final showTimes = List<String>.from(cinemaData['showTimes'] ?? []);
                            final imagePath = _getTheaterImage(theaterName);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _availableTheaterCard(
                                context: context,
                                theaterName: theaterName,
                                imagePath: imagePath,
                                showTimes: showTimes,
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 24),
                    ],

                    // FROM THEATER: Show cinema info
                    if (_comingFromTheater) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE50914).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Color(0xFFE50914),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Cinema',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.preselectedCinema!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFFE50914),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),

              // Bottom spacing for button
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),

      // Bottom Continue Booking Button
      bottomNavigationBar: _comingFromTheater
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F0F),
                border: Border(
                  top: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ShowtimeSelection(
                            movieName: widget.movie['title'] ?? 'Unknown Movie',
                            cinemaName: widget.preselectedCinema!,
                            movieImageUrl: TmdbService.getImageUrl(
                              widget.movie['poster_path'] ?? widget.movie['backdrop_path'] ?? '',
                            ),
                            rating: (widget.movie['vote_average'] ?? 0).toString(),
                            availableShowTimes: widget.preselectedShowTimes,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE50914),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Continue Booking',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  String _getTheaterImage(String theaterName) {
    switch (theaterName) {
      case 'Archana Cinema':
        return 'assets/images/theaters/archana.jfif';
      case 'GK Cinemax':
        return 'assets/images/theaters/gk.jfif';
      case 'PCA Cinemas':
        return 'assets/images/theaters/pca.jfif';
      case 'Shanthi Cinema':
        return 'assets/images/theaters/shanthi.jpeg';
      default:
        return 'assets/images/theaters/archana.jfif';
    }
  }

  // Dynamic theater card for available cinemas only (passes showTimes for the specific cinema)
  Widget _availableTheaterCard({
    required BuildContext context,
    required String theaterName,
    required String imagePath,
    required List<String> showTimes,
  }) {
    return SizedBox(
      height: 80,
      width: double.infinity,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShowtimeSelection(
                movieName: widget.movie['title'] ?? 'Unknown Movie',
                cinemaName: theaterName,
                movieImageUrl: TmdbService.getImageUrl(
                  widget.movie['poster_path'] ?? widget.movie['backdrop_path'] ?? '',
                ),
                rating: (widget.movie['vote_average'] ?? 0).toString(),
                availableShowTimes: showTimes.isNotEmpty ? showTimes : null,
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
            color: const Color(0xFF1E1E1E),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
                child: Image.asset(
                  imagePath,
                  height: 80,
                  width: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 80,
                    width: 90,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      theaterName,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    if (showTimes.isNotEmpty)
                      Text(
                        showTimes.join('  •  '),
                        style: TextStyle(color: Colors.grey.withOpacity(0.7), fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}
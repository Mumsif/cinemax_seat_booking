import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cinemax_seat_booking/core/services/admin_service.dart';
import 'package:cinemax_seat_booking/core/services/tmdb_service.dart';

class AdminMovieManager extends StatefulWidget {
  final String?
  restrictedCinema; // null = super admin, "Cinema Name" = cinema admin

  const AdminMovieManager({super.key, this.restrictedCinema});

  @override
  State<AdminMovieManager> createState() => _AdminMovieManagerState();
}

class _AdminMovieManagerState extends State<AdminMovieManager> {
  late String _selectedCinema;
  bool _isLoading = true;
  List<dynamic> _apiMovies = [];
  List<Map<String, dynamic>> _activeMovies = [];
  List<Map<String, dynamic>> _movieHistory = [];

  final List<String> _allCinemas = [
    'Archana Cinema',
    'GK Cinemax',
    'Shanthi Cinema',
    'PCA Cinemas',
  ];

  final List<String> _allShowTimes = [
    '10:30 AM',
    '02:30 PM',
    '06:30 PM',
    '10:30 PM',
  ];

  /// TRUE if this admin can only see their own cinema
  bool get _isCinemaAdmin =>
      widget.restrictedCinema != null &&
      widget.restrictedCinema!.isNotEmpty &&
      widget.restrictedCinema != 'null';

  /// TRUE if super admin (can switch between all cinemas)
  bool get _isSuperAdmin => !_isCinemaAdmin;

  @override
  void initState() {
    super.initState();

    // CRITICAL: Set cinema based on admin type
    if (_isCinemaAdmin) {
      // Cinema admin: locked to their cinema
      _selectedCinema = widget.restrictedCinema!;
      print('DEBUG: Cinema admin logged in, cinema = $_selectedCinema');
    } else {
      // Super admin: default to first cinema, but can switch
      _selectedCinema = _allCinemas.first;
      print('DEBUG: Super admin logged in, default cinema = $_selectedCinema');
    }

    _loadMovies();
  }

  Future<void> _loadMovies() async {
    setState(() => _isLoading = true);

    try {
      // Fetch from TMDB API (same for all admins)
      _apiMovies = await TmdbService.getNowPlaying();

      // Load active movies for SELECTED cinema only
      final activeSnapshot = await FirebaseFirestore.instance
          .collection('movies')
          .where('cinemaName', isEqualTo: _selectedCinema)
          .where('status', isEqualTo: 'active')
          .get();

      _activeMovies = activeSnapshot.docs.map((d) {
        final data = d.data();
        data['docId'] = d.id;
        return data;
      }).toList();

      // Load expired movies for SELECTED cinema (last 2 weeks)
      final twoWeeksAgo = DateTime.now().subtract(const Duration(days: 14));
      final historySnapshot = await FirebaseFirestore.instance
          .collection('movies')
          .where('cinemaName', isEqualTo: _selectedCinema)
          .where('status', isEqualTo: 'expired')
          .where('autoRemoveAt', isGreaterThan: Timestamp.fromDate(twoWeeksAgo))
          .get();

      _movieHistory = historySnapshot.docs.map((d) => d.data()).toList();

      print(
        'DEBUG: Loaded ${_activeMovies.length} active, ${_movieHistory.length} expired for $_selectedCinema',
      );
    } catch (e) {
      print('Error loading movies: $e');
    }

    setState(() => _isLoading = false);
  }

  void _showCinemaSelector() {
    if (_isCinemaAdmin) return; // Cinema admin cannot switch

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Cinema',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ..._allCinemas.map(
                (cinema) => ListTile(
                  title: Text(
                    cinema,
                    style: TextStyle(
                      color: _selectedCinema == cinema
                          ? const Color(0xFFE50914)
                          : Colors.white,
                      fontWeight: _selectedCinema == cinema
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: _selectedCinema == cinema
                      ? const Icon(Icons.check_circle, color: Color(0xFFE50914))
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedCinema = cinema);
                    _loadMovies();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddMovieBottomSheet(dynamic movie) {
    final List<String> selectedShowTimes = [];

    final String title = movie['title'] ?? 'Unknown';
    final String posterPath = movie['poster_path'] ?? '';
    final String backdropPath = movie['backdrop_path'] ?? '';
    final String releaseDate = movie['release_date'] ?? '';
    final double rating = (movie['vote_average'] as num?)?.toDouble() ?? 0.0;
    final int movieId = movie['id'] ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FutureBuilder(
        future: TmdbService.getMovieDetails(movieId),
        builder: (context, snapshot) {
          final details = snapshot.data;
          final duration = details?['runtime'] != null
              ? _formatDuration(details!['runtime'])
              : 'TBD';

          return StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    // Drag Handle
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade600,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Add Movie',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    const Divider(color: Color(0xFF333333)),

                    // Scrollable Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Poster from TMDB
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                TmdbService.getImageUrl(posterPath),
                                height: 220,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 220,
                                  color: Colors.grey.shade800,
                                  child: const Icon(
                                    Icons.movie,
                                    color: Colors.grey,
                                    size: 60,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Movie Name (read-only from API)
                            _buildLabel('Movie Name'),
                            _buildReadOnlyField(title),
                            const SizedBox(height: 16),

                            // Duration & Rating Row (from API)
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildLabel('Duration'),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F0F0F),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.schedule,
                                              color: Color(0xFFE50914),
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              duration,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildLabel('Rating'),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F0F0F),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              color: Colors.amber,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${rating.toStringAsFixed(1)} / 10',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Cinema (pre-filled, read-only)
                            _buildLabel('Cinema'),
                            _buildReadOnlyField(_selectedCinema),
                            const SizedBox(height: 20),

                            // Show Times (Admin selects)
                            _buildLabel('Show Times *'),
                            const Text(
                              'Select up to 4 time slots',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),

                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _allShowTimes.map((time) {
                                final isSelected = selectedShowTimes.contains(
                                  time,
                                );
                                return GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      if (isSelected) {
                                        selectedShowTimes.remove(time);
                                      } else if (selectedShowTimes.length < 4) {
                                        selectedShowTimes.add(time);
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFE50914)
                                          : const Color(0xFF0F0F0F),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFFE50914)
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                    child: Text(
                                      time,
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey,
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),

                            // Auto-Remove Info
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F0F0F),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade800),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: Colors.grey,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'This movie will auto-remove after 2 weeks (${_formatDate(DateTime.now().add(const Duration(days: 14)))})',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),

                    // Add Movie Button
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: selectedShowTimes.isEmpty
                              ? null
                              : () => _addMovie(
                                  movieId: movieId,
                                  title: title,
                                  posterPath: posterPath,
                                  backdropPath: backdropPath,
                                  duration: duration,
                                  rating: rating,
                                  showTimes: selectedShowTimes,
                                  releaseDate: releaseDate,
                                  context: context,
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE50914),
                            disabledBackgroundColor: Colors.grey.shade800,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Add Movie',
                            style: TextStyle(
                              color: selectedShowTimes.isEmpty
                                  ? Colors.grey
                                  : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDuration(int? minutes) {
    if (minutes == null || minutes <= 0) return 'TBD';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _addMovie({
    required int movieId,
    required String title,
    required String posterPath,
    required String backdropPath,
    required String duration,
    required double rating,
    required List<String> showTimes,
    required String releaseDate,
    required BuildContext context,
  }) async {
    if (_activeMovies.length >= 2) {
      Navigator.pop(context);
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 2 active movies allowed. Remove one first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final now = DateTime.now();
      final autoRemove = now.add(const Duration(days: 14));

      await FirebaseFirestore.instance.collection('movies').add({
        'cinemaName': _selectedCinema,
        'movieId': movieId,
        'movieName': title,
        'posterUrl': TmdbService.getImageUrl(posterPath),
        'backdropUrl': TmdbService.getImageUrl(backdropPath),
        'duration': duration,
        'rating': rating,
        'showTimes': showTimes,
        'status': 'active',
        'addedAt': Timestamp.fromDate(now),
        'autoRemoveAt': Timestamp.fromDate(autoRemove),
        'addedBy': AdminService.adminEmail ?? 'unknown',
        'releaseDate': releaseDate,
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text('$title added to $_selectedCinema'),
          backgroundColor: Colors.green,
        ),
      );

      _loadMovies();
    } catch (e) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteMovie(String docId, String movieName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Remove Movie',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Remove $movieName from $_selectedCinema?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('movies').doc(docId).update({
        'status': 'expired',
        'removedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$movieName removed'),
          backgroundColor: Colors.orange,
        ),
      );

      _loadMovies();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final sp = w / 375;

    // FIX: Proper title for both admin types
    final String appBarTitle = _isCinemaAdmin
        ? '$_selectedCinema Movies'
        : '$_selectedCinema | Super Admin';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text(appBarTitle, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E1E),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Cinema selector ONLY for super admin
          if (_isSuperAdmin)
            IconButton(
              icon: const Icon(Icons.swap_horiz, color: Colors.white),
              tooltip: 'Switch Cinema',
              onPressed: _showCinemaSelector,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE50914)),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16 * sp),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cinema indicator for cinema admin
                  if (_isCinemaAdmin)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12 * sp),
                      margin: EdgeInsets.only(bottom: 12 * sp),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE50914).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFE50914).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Color(0xFFE50914),
                            size: 18,
                          ),
                          SizedBox(width: 8 * sp),
                          Text(
                            'Managing: $_selectedCinema',
                            style: TextStyle(
                              color: const Color(0xFFE50914),
                              fontSize: 13 * sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // TMDB Movies Row
                  Text(
                    'Select a Movie',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18 * sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4 * sp),
                  Text(
                    'Tap a movie to add to $_selectedCinema',
                    style: TextStyle(color: Colors.grey, fontSize: 12 * sp),
                  ),
                  SizedBox(height: 12 * sp),

                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _apiMovies.length,
                      itemBuilder: (context, index) {
                        final movie = _apiMovies[index];
                        final posterPath = movie['poster_path'] ?? '';
                        final title = movie['title'] ?? 'Unknown';
                        final releaseDate = movie['release_date'] ?? '';

                        return GestureDetector(
                          onTap: () => _showAddMovieBottomSheet(movie),
                          child: Container(
                            width: 130,
                            margin: const EdgeInsets.only(right: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    TmdbService.getImageUrl(posterPath),
                                    height: 160,
                                    width: 130,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 160,
                                      width: 130,
                                      color: Colors.grey.shade800,
                                      child: const Icon(
                                        Icons.movie,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  releaseDate,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  SizedBox(height: 24 * sp),

                  // Active Movies
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Now Showing at $_selectedCinema',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18 * sp,
                                fontWeight: FontWeight.bold,
                                height: 1.0,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_activeMovies.length >= 2)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8 * sp,
                                vertical: 4 * sp,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6 * sp),
                              ),
                              child: Text(
                                'MAX REACHED',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10 * sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        '(${_activeMovies.length}/2)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16 * sp,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12 * sp),

                  if (_activeMovies.isEmpty)
                    Container(
                      padding: EdgeInsets.all(20 * sp),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'No active movies at $_selectedCinema\nSelect a movie from above to add',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ..._activeMovies.map(
                      (movie) => _buildActiveMovieCard(movie, sp),
                    ),

                  SizedBox(height: 24 * sp),

                  // Movie History
                  if (_movieHistory.isNotEmpty) ...[
                    Text(
                      'Recently Expired at $_selectedCinema',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16 * sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12 * sp),
                    ..._movieHistory.map(
                      (movie) => _buildHistoryCard(movie, sp),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildActiveMovieCard(Map<String, dynamic> movie, double sp) {
    final docId = movie['docId'] ?? '';
    final movieName = movie['movieName'] ?? 'Unknown';
    final posterUrl = movie['posterUrl'] ?? '';
    final duration = movie['duration'] ?? '-';
    final rating = movie['rating'] ?? '-';
    final showTimes = (movie['showTimes'] as List?)?.cast<String>() ?? [];
    final autoRemoveAt = (movie['autoRemoveAt'] as Timestamp?)?.toDate();

    final daysRemaining = autoRemoveAt != null
        ? autoRemoveAt.difference(DateTime.now()).inDays
        : 0;

    return Container(
      margin: EdgeInsets.only(bottom: 12 * sp),
      padding: EdgeInsets.all(14 * sp),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12 * sp),
        border: Border.all(color: const Color(0xFFE50914).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              posterUrl,
              width: 80 * sp,
              height: 120 * sp,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 80 * sp,
                height: 120 * sp,
                color: Colors.grey.shade800,
                child: const Icon(Icons.movie, color: Colors.grey),
              ),
            ),
          ),
          SizedBox(width: 14 * sp),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movieName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16 * sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4 * sp),
                Row(
                  children: [
                    Icon(Icons.schedule, color: Colors.grey, size: 14 * sp),
                    SizedBox(width: 4 * sp),
                    Text(
                      duration,
                      style: TextStyle(color: Colors.grey, fontSize: 12 * sp),
                    ),
                    SizedBox(width: 12 * sp),
                    Icon(Icons.star, color: Colors.amber, size: 14 * sp),
                    SizedBox(width: 4 * sp),
                    Text(
                      '$rating',
                      style: TextStyle(color: Colors.grey, fontSize: 12 * sp),
                    ),
                  ],
                ),
                SizedBox(height: 8 * sp),
                Wrap(
                  spacing: 6,
                  children: showTimes
                      .map(
                        (t) => Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8 * sp,
                            vertical: 4 * sp,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F0F0F),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade700),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10 * sp,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                SizedBox(height: 8 * sp),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      daysRemaining > 0
                          ? '⏳ $daysRemaining days left'
                          : '⏳ Expires today',
                      style: TextStyle(
                        color: daysRemaining <= 3
                            ? Colors.orange
                            : Colors.green,
                        fontSize: 11 * sp,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _deleteMovie(docId, movieName),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10 * sp,
                          vertical: 4 * sp,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 14 * sp,
                            ),
                            SizedBox(width: 4 * sp),
                            Text(
                              'Remove',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 11 * sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> movie, double sp) {
    final movieName = movie['movieName'] ?? 'Unknown';
    final posterUrl = movie['posterUrl'] ?? '';
    final removedAt = (movie['removedAt'] as Timestamp?)?.toDate();

    return Container(
      margin: EdgeInsets.only(bottom: 8 * sp),
      padding: EdgeInsets.all(10 * sp),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8 * sp),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              posterUrl,
              width: 50 * sp,
              height: 75 * sp,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 50 * sp,
                height: 75 * sp,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          SizedBox(width: 12 * sp),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movieName,
                  style: TextStyle(color: Colors.grey, fontSize: 14 * sp),
                ),
                if (removedAt != null)
                  Text(
                    'Removed: ${_formatDate(removedAt)}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11 * sp,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8 * sp, vertical: 4 * sp),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'EXPIRED',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 10 * sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
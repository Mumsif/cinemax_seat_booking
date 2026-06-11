import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DailyReportScreen extends StatefulWidget {
  final String? restrictedCinema;

  const DailyReportScreen({super.key, this.restrictedCinema});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _isSuperAdmin = false;
  String? _resolvedCinema;
  String? _errorMessage;
  String _debugQuery = '';
  bool _showAllTime = false;

  // Report Data
  int _totalSeatsBooked = 0;
  int _totalBookings = 0;
  double _totalRevenue = 0;
  Map<String, MovieReport> _movieReports = {};
  Map<String, int> _showtimeDistribution = {};

  final List<String> _allShowTimes = [
    '6:00 AM',
    '10:30 AM',
    '2:30 PM',
    '6:30 PM',
    '10:30 PM',
  ];

  final List<String> _allCinemas = [
    'Archana Cinema',
    'GK Cinemax',
    'Shanthi Cinema',
    'PCA Cinemas',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _resolveAdminType();
    _loadReport();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _resolveAdminType() {
    final param = widget.restrictedCinema;
    if (param != null && param.isNotEmpty && param != 'null') {
      _isSuperAdmin = false;
      _resolvedCinema = param;
    } else {
      _isSuperAdmin = true;
      _resolvedCinema = null;
    }
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _debugQuery = '';
    });
    _animController.reset();

    try {
      // FIX: Use client-side filtering for cinema to avoid composite index requirement
      Query ticketsQuery = FirebaseFirestore.instance.collection('tickets');

      // Only filter by date on server (single field index)
      if (!_showAllTime) {
        final dateStr =
            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
        ticketsQuery = ticketsQuery.where('date', isEqualTo: dateStr);
        _debugQuery = 'date = $dateStr';
      } else {
        _debugQuery = 'All time';
      }

      final ticketsSnapshot = await ticketsQuery.get();
      if (!mounted) return;

      _totalSeatsBooked = 0;
      _totalBookings = 0;
      _totalRevenue = 0;
      _movieReports = {};
      _showtimeDistribution = {};

      // FIX: Client-side cinema filter (no composite index needed)
      for (final doc in ticketsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Skip if cinema doesn't match (client-side filter)
        if (_resolvedCinema != null) {
          final ticketCinema = (data['cinemaName'] ?? '').toString();
          if (ticketCinema != _resolvedCinema) continue;
        }

        final statusRaw = data['status'];
        final status = statusRaw is String ? statusRaw : 'confirmed';
        if (status == 'cancelled') continue;

        List<String> seats = [];
        final seatsRaw = data['seats'];
        if (seatsRaw is List) {
          seats = seatsRaw.map((e) => e.toString()).toList();
        }
        final seatCount = seats.length;
        final total = (data['total'] as num?)?.toDouble() ?? 0;
        final movieName = (data['movieName'] ?? 'Unknown Movie').toString();
        final time = (data['time'] ?? data['showTime'] ?? '-').toString();
        final cinemaName = (data['cinemaName'] ?? 'Unknown').toString();

        _totalSeatsBooked += seatCount;
        _totalBookings++;
        _totalRevenue += total;

        _movieReports.putIfAbsent(
          movieName,
          () => MovieReport(
            movieName: movieName,
            cinemaName: cinemaName,
          ),
        );
        _movieReports[movieName]!.addBooking(seatCount, total, time);

        final normalizedTime = _normalizeShowTime(time);
        if (normalizedTime != null) {
          _showtimeDistribution[normalizedTime] =
              (_showtimeDistribution[normalizedTime] ?? 0) + seatCount;
        }
      }

      final sortedEntries = _movieReports.entries.toList()
        ..sort((a, b) => b.value.totalSeats.compareTo(a.value.totalSeats));
      _movieReports = Map.fromEntries(sortedEntries);

      _animController.forward();
    } catch (e) {
      debugPrint('Error loading report: $e');
      if (mounted) setState(() => _errorMessage = e.toString());
    }

    if (mounted) setState(() => _isLoading = false);
  }

  String? _normalizeShowTime(String time) {
    final lower = time.toLowerCase().trim();

    if (lower.contains('6') && lower.contains('am')) return '6:00 AM';
    if (lower.contains('06') && lower.contains('am')) return '6:00 AM';

    if (lower.contains('10') && lower.contains('30') && lower.contains('am')) return '10:30 AM';
    if (lower.contains('10:30') && lower.contains('am')) return '10:30 AM';

    if (lower.contains('2') && lower.contains('30') && lower.contains('pm')) return '2:30 PM';
    if (lower.contains('14') && lower.contains('30')) return '2:30 PM';
    if (lower.contains('2:30') && lower.contains('pm')) return '2:30 PM';

    if (lower.contains('6') && lower.contains('30') && lower.contains('pm')) return '6:30 PM';
    if (lower.contains('18') && lower.contains('30')) return '6:30 PM';
    if (lower.contains('6:30') && lower.contains('pm')) return '6:30 PM';

    if (lower.contains('10') && lower.contains('30') && lower.contains('pm')) return '10:30 PM';
    if (lower.contains('22') && lower.contains('30')) return '10:30 PM';
    if (lower.contains('10:30') && lower.contains('pm')) return '10:30 PM';

    if (lower.contains('am') && !lower.contains('10')) return '6:00 AM';
    if (lower.contains('am') && lower.contains('10')) return '10:30 AM';
    if (lower.contains('pm') && lower.contains('2')) return '2:30 PM';
    if (lower.contains('pm') && lower.contains('6')) return '6:30 PM';
    if (lower.contains('pm') && lower.contains('10')) return '10:30 PM';

    return null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFE50914),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF0F0F0F),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      if (!mounted) return;
      setState(() {
        _selectedDate = picked;
        _showAllTime = false;
      });
      _loadReport();
    }
  }

  void _toggleAllTime() {
    setState(() => _showAllTime = !_showAllTime);
    _loadReport();
  }

  void _showCinemaSelector() {
    if (!_isSuperAdmin) return;

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
                      color: _resolvedCinema == cinema
                          ? const Color(0xFFE50914)
                          : Colors.white,
                      fontWeight: _resolvedCinema == cinema
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: _resolvedCinema == cinema
                      ? const Icon(Icons.check_circle, color: Color(0xFFE50914))
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _resolvedCinema = cinema);
                    _loadReport();
                  },
                ),
              ),
              ListTile(
                title: const Text(
                  'All Cinemas',
                  style: TextStyle(
                    color: Color(0xFFE50914),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: _resolvedCinema == null
                    ? const Icon(Icons.check_circle, color: Color(0xFFE50914))
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _resolvedCinema = null);
                  _loadReport();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final sp = w / 375;

    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate);
    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadReport,
          color: const Color(0xFFE50914),
          backgroundColor: const Color(0xFF1E1E1E),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // FIX: Compact header to prevent overflow
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16 * sp),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: Back + Title + Actions
                      Row(
                        children: [
                          // Back button
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: EdgeInsets.all(8 * sp),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                                size: 18 * sp,
                              ),
                            ),
                          ),
                          SizedBox(width: 12 * sp),
                          // Title and date
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Daily Report',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22 * sp,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                SizedBox(height: 2 * sp),
                                GestureDetector(
                                  onTap: _pickDate,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        color: const Color(0xFFE50914),
                                        size: 12 * sp,
                                      ),
                                      SizedBox(width: 4 * sp),
                                      Flexible(
                                        child: Text(
                                          _showAllTime
                                              ? 'All Time'
                                              : (isToday ? 'Today · $dateStr' : dateStr),
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12 * sp,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      SizedBox(width: 2 * sp),
                                      Icon(
                                        Icons.arrow_drop_down,
                                        color: Colors.grey,
                                        size: 14 * sp,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Action buttons row
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // All toggle
                              GestureDetector(
                                onTap: _toggleAllTime,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8 * sp,
                                    vertical: 5 * sp,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _showAllTime
                                        ? const Color(0xFFE50914).withOpacity(0.2)
                                        : const Color(0xFF1E1E1E),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: _showAllTime
                                          ? const Color(0xFFE50914)
                                          : Colors.grey.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'All',
                                    style: TextStyle(
                                      color: _showAllTime
                                          ? const Color(0xFFE50914)
                                          : Colors.grey,
                                      fontSize: 10 * sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 6 * sp),
                              // Cinema selector (super admin only)
                              if (_isSuperAdmin)
                                GestureDetector(
                                  onTap: _showCinemaSelector,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8 * sp,
                                      vertical: 5 * sp,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E1E),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFFE50914).withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          color: const Color(0xFFE50914),
                                          size: 12 * sp,
                                        ),
                                        SizedBox(width: 3 * sp),
                                        Text(
                                          _resolvedCinema ?? 'All',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10 * sp,
                                            fontWeight: FontWeight.w600,
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
                      // Debug info
                      if (_debugQuery.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 6 * sp, left: 46 * sp),
                          child: Text(
                            'Filter: $_debugQuery',
                            style: TextStyle(
                              color: Colors.grey.withOpacity(0.5),
                              fontSize: 9 * sp,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Loading
              if (_isLoading)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            color: const Color(0xFFE50914),
                            strokeWidth: 3,
                          ),
                        ),
                        SizedBox(height: 16 * sp),
                        Text(
                          'Loading report...',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14 * sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              // Error State
              else if (_errorMessage != null)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24 * sp),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 56 * sp,
                          ),
                          SizedBox(height: 16 * sp),
                          Text(
                            'Failed to load report',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 18 * sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8 * sp),
                          Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12 * sp,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 24 * sp),
                          ElevatedButton.icon(
                            onPressed: _loadReport,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE50914),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              // Empty State
              else if (_totalBookings == 0)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          color: Colors.grey.withOpacity(0.3),
                          size: 64 * sp,
                        ),
                        SizedBox(height: 16 * sp),
                        Text(
                          'No bookings found',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16 * sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 6 * sp),
                        Text(
                          _showAllTime
                              ? 'No tickets in the database'
                              : 'No tickets for this date',
                          style: TextStyle(
                            color: Colors.grey.withOpacity(0.6),
                            fontSize: 12 * sp,
                          ),
                        ),
                        SizedBox(height: 6 * sp),
                        Text(
                          'Filter: $_debugQuery',
                          style: TextStyle(
                            color: Colors.grey.withOpacity(0.4),
                            fontSize: 10 * sp,
                          ),
                        ),
                        SizedBox(height: 20 * sp),
                        // FIX: Better button styling
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ActionButton(
                              icon: Icons.calendar_today,
                              label: 'Pick Date',
                              isPrimary: true,
                              onTap: _pickDate,
                              sp: sp,
                            ),
                            SizedBox(width: 10 * sp),
                            _ActionButton(
                              icon: Icons.all_inclusive,
                              label: 'Show All',
                              isPrimary: false,
                              onTap: _toggleAllTime,
                              sp: sp,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              // Data Content
              else ...[
                // Summary Cards
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16 * sp),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            icon: Icons.event_seat,
                            iconColor: const Color(0xFFE50914),
                            title: 'Total Seats',
                            value: _totalSeatsBooked.toString(),
                            subtitle: 'Booked today',
                            delay: 0,
                            animController: _animController,
                            sp: sp,
                          ),
                        ),
                        SizedBox(width: 12 * sp),
                        Expanded(
                          child: _SummaryCard(
                            icon: Icons.receipt,
                            iconColor: const Color(0xFFD4AF37),
                            title: 'Bookings',
                            value: _totalBookings.toString(),
                            subtitle: 'Transactions',
                            delay: 0.1,
                            animController: _animController,
                            sp: sp,
                          ),
                        ),
                        SizedBox(width: 12 * sp),
                        Expanded(
                          child: _SummaryCard(
                            icon: Icons.payments,
                            iconColor: Colors.green,
                            title: 'Revenue',
                            value: 'Rs. ${_formatNumber(_totalRevenue)}',
                            subtitle: 'Total earnings',
                            delay: 0.2,
                            animController: _animController,
                            sp: sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(child: SizedBox(height: 24 * sp)),

                // Showtime Distribution
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16 * sp),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Showtime Distribution',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18 * sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4 * sp),
                        Text(
                          'Seats booked per time slot',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12 * sp,
                          ),
                        ),
                        SizedBox(height: 16 * sp),
                        Container(
                          padding: EdgeInsets.all(16 * sp),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                          child: Column(
                            children: _allShowTimes.map((time) {
                              final count = _showtimeDistribution[time] ?? 0;
                              final maxCount = _showtimeDistribution.values.isEmpty
                                  ? 1
                                  : _showtimeDistribution.values.reduce((a, b) => a > b ? a : b);

                              double percentage = 0.0;
                              if (maxCount > 0) {
                                percentage = (count / maxCount).toDouble();
                                if (percentage.isNaN || percentage.isInfinite) {
                                  percentage = 0.0;
                                }
                                percentage = percentage.clamp(0.0, 1.0);
                              }

                              return Padding(
                                padding: EdgeInsets.only(bottom: 12 * sp),
                                child: _ShowtimeBar(
                                  time: time,
                                  count: count,
                                  percentage: percentage,
                                  totalSeats: _totalSeatsBooked,
                                  sp: sp,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(child: SizedBox(height: 24 * sp)),

                // Movie Breakdown
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16 * sp),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Movie Breakdown',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18 * sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10 * sp,
                                vertical: 4 * sp,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE50914).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_movieReports.length} Movies',
                                style: TextStyle(
                                  color: const Color(0xFFE50914),
                                  fontSize: 11 * sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4 * sp),
                        Text(
                          'Detailed per-movie statistics',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12 * sp,
                          ),
                        ),
                        SizedBox(height: 16 * sp),
                      ],
                    ),
                  ),
                ),

                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final movie = _movieReports.values.elementAt(index);
                      final delay = 0.3 + (index * 0.05);
                      return _MovieReportCard(
                        report: movie,
                        allShowTimes: _allShowTimes,
                        delay: delay,
                        animController: _animController,
                        sp: sp,
                      );
                    },
                    childCount: _movieReports.length,
                  ),
                ),

                SliverToBoxAdapter(child: SizedBox(height: 32 * sp)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(double num) {
    if (num >= 1000000) {
      return '${(num / 1000000).toStringAsFixed(1)}M';
    } else if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}K';
    }
    return num.toStringAsFixed(0);
  }
}

// ─── NEW: Action Button Widget (Better UX) ───────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;
  final double sp;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isPrimary,
    required this.onTap,
    required this.sp,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 14 * sp,
          vertical: 10 * sp,
        ),
        decoration: BoxDecoration(
          color: isPrimary
              ? const Color(0xFFE50914)
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
          border: isPrimary
              ? null
              : Border.all(
                  color: Colors.grey.withOpacity(0.3),
                  width: 1,
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isPrimary ? Colors.white : Colors.grey,
              size: 14 * sp,
            ),
            SizedBox(width: 6 * sp),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : Colors.grey,
                fontSize: 12 * sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Summary Card Widget ───────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String subtitle;
  final double delay;
  final AnimationController animController;
  final double sp;

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.delay,
    required this.animController,
    required this.sp,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animController,
      builder: (context, child) {
        final animation = Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: animController,
            curve: Interval(delay, delay + 0.4, curve: Curves.easeOut),
          ),
        );

        return Transform.translate(
          offset: Offset(0, 20 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: Container(
              padding: EdgeInsets.all(14 * sp),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: iconColor.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(8 * sp),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 20 * sp,
                    ),
                  ),
                  SizedBox(height: 12 * sp),
                  Text(
                    value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22 * sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 2 * sp),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12 * sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2 * sp),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10 * sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Showtime Bar Widget ───────────────────────────────────────────────────

class _ShowtimeBar extends StatelessWidget {
  final String time;
  final int count;
  final double percentage;
  final int totalSeats;
  final double sp;

  const _ShowtimeBar({
    required this.time,
    required this.count,
    required this.percentage,
    required this.totalSeats,
    required this.sp,
  });

  @override
  Widget build(BuildContext context) {
    final validPercentage = percentage.isNaN || percentage.isInfinite || percentage < 0
        ? 0.0
        : percentage > 1.0
            ? 1.0
            : percentage;

    final percentOfTotal = totalSeats > 0 ? (count / totalSeats * 100) : 0;

    return Row(
      children: [
        SizedBox(
          width: 70 * sp,
          child: Text(
            time,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12 * sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(width: 12 * sp),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 28 * sp,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F0F),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                    height: 28 * sp,
                    width: constraints.maxWidth * validPercentage,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFE50914),
                          const Color(0xFFE50914).withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  );
                },
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10 * sp),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$count seats',
                        style: TextStyle(
                          color: count > 0 ? Colors.white : Colors.grey,
                          fontSize: 11 * sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (percentOfTotal > 0)
                        Text(
                          '${percentOfTotal.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10 * sp,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Movie Report Card Widget ─────────────────────────────────────────────

class _MovieReportCard extends StatelessWidget {
  final MovieReport report;
  final List<String> allShowTimes;
  final double delay;
  final AnimationController animController;
  final double sp;

  const _MovieReportCard({
    required this.report,
    required this.allShowTimes,
    required this.delay,
    required this.animController,
    required this.sp,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animController,
      builder: (context, child) {
        final animation = Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: animController,
            curve: Interval(delay, delay + 0.3, curve: Curves.easeOut),
          ),
        );

        return Transform.translate(
          offset: Offset(0, 30 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: 16 * sp,
                vertical: 6 * sp,
              ),
              padding: EdgeInsets.all(16 * sp),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.movieName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16 * sp,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2 * sp),
                            Text(
                              report.cinemaName,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 11 * sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10 * sp,
                          vertical: 4 * sp,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE50914).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${report.totalSeats} seats',
                          style: TextStyle(
                            color: const Color(0xFFE50914),
                            fontSize: 11 * sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 12 * sp),

                  Row(
                    children: [
                      _MovieStat(
                        icon: Icons.receipt,
                        label: '${report.bookingCount} bookings',
                        sp: sp,
                      ),
                      SizedBox(width: 16 * sp),
                      _MovieStat(
                        icon: Icons.payments,
                        label: 'Rs. ${report.totalRevenue.toStringAsFixed(0)}',
                        sp: sp,
                      ),
                      SizedBox(width: 16 * sp),
                      _MovieStat(
                        icon: Icons.trending_up,
                        label: 'Rs. ${report.avgPerBooking.toStringAsFixed(0)} avg',
                        sp: sp,
                      ),
                    ],
                  ),

                  SizedBox(height: 12 * sp),

                  const Divider(color: Color(0xFF333333)),

                  SizedBox(height: 10 * sp),

                  Text(
                    'Showtimes',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11 * sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8 * sp),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allShowTimes.map((time) {
                      final count = report.showtimeCounts[time] ?? 0;
                      final isActive = count > 0;

                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10 * sp,
                          vertical: 5 * sp,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFFE50914).withOpacity(0.15)
                              : const Color(0xFF0F0F0F),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive
                                ? const Color(0xFFE50914).withOpacity(0.3)
                                : Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              time,
                              style: TextStyle(
                                color: isActive ? Colors.white : Colors.grey,
                                fontSize: 11 * sp,
                                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            if (isActive) ...[
                              SizedBox(width: 4 * sp),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 4 * sp,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE50914),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9 * sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MovieStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final double sp;

  const _MovieStat({
    required this.icon,
    required this.label,
    required this.sp,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.grey,
          size: 14 * sp,
        ),
        SizedBox(width: 4 * sp),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 11 * sp,
          ),
        ),
      ],
    );
  }
}

// ─── Movie Report Model ───────────────────────────────────────────────────

class MovieReport {
  final String movieName;
  final String cinemaName;
  int totalSeats = 0;
  int bookingCount = 0;
  double totalRevenue = 0;
  Map<String, int> showtimeCounts = {};

  MovieReport({
    required this.movieName,
    required this.cinemaName,
  });

  void addBooking(int seats, double total, String time) {
    totalSeats += seats;
    bookingCount++;
    totalRevenue += total;

    final normalized = _normalizeTime(time);
    if (normalized != null) {
      showtimeCounts[normalized] = (showtimeCounts[normalized] ?? 0) + seats;
    }
  }

  double get avgPerBooking => bookingCount > 0 ? totalRevenue / bookingCount : 0;

  String? _normalizeTime(String time) {
    final lower = time.toLowerCase().trim();
    if (lower.contains('6') && lower.contains('am')) return '6:00 AM';
    if (lower.contains('10') && lower.contains('30') && lower.contains('am')) return '10:30 AM';
    if ((lower.contains('2') || lower.contains('14')) && lower.contains('30') && (lower.contains('pm') || lower.contains('14'))) return '2:30 PM';
    if ((lower.contains('6') || lower.contains('18')) && lower.contains('30') && (lower.contains('pm') || lower.contains('18'))) return '6:30 PM';
    if ((lower.contains('10') || lower.contains('22')) && lower.contains('30') && (lower.contains('pm') || lower.contains('22'))) return '10:30 PM';
    return null;
  }
}
import 'dart:async';
import 'dart:math';
import 'package:cinemax_seat_booking/presentation/views/ticket_screen.dart';
import 'package:cinemax_seat_booking/presentation/widgets/animated_seat_widget.dart';
import 'package:cinemax_seat_booking/presentation/widgets/cinema_screen_painter.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SeatSelectionScreen extends StatefulWidget {
  final String movieName;
  final String cinemaName;
  final String showTime;
  final String movieImageUrl;
  final DateTime selectedDate;
  final String rating;

  const SeatSelectionScreen({
    super.key,
    required this.movieName,
    required this.cinemaName,
    required this.showTime,
    required this.movieImageUrl,
    required this.selectedDate,
    required this.rating,
  });

  @override
  State<SeatSelectionScreen> createState() => _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends State<SeatSelectionScreen>
    with TickerProviderStateMixin {
  // 0=aisle, 1=available, 2=booked, 3=selected, 4=blocked
  late List<List<int>> seats;
  Map<String, dynamic> _bookedSeats = {};
  StreamSubscription? _seatSubscription;

  // ── Animation controllers ──
  late AnimationController _screenGlowController;
  late Animation<double> _screenGlowAnim;
  late AnimationController _panelSlideController;
  late Animation<Offset> _panelSlideAnim;
  late AnimationController _legendController;
  late Animation<double> _legendFadeAnim;

  // Price
  static const double _pricePerSeat = 250.0;

  @override
  void initState() {
    super.initState();
    _initSeats();
    _listenToBookedSeats();
    _initAnimations();
  }

  void _initAnimations() {
    // ── Screen glow pulse ──
    _screenGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _screenGlowAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _screenGlowController, curve: Curves.easeInOut),
    );

    // ── Bottom panel slide ──
    _panelSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _panelSlideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _panelSlideController, curve: Curves.easeOutCubic),
    );

    // ── Legend fade in ──
    _legendController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _legendFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _legendController, curve: Curves.easeOut),
    );
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _legendController.forward();
    });
  }

  @override
  void dispose() {
    _seatSubscription?.cancel();
    _screenGlowController.dispose();
    _panelSlideController.dispose();
    _legendController.dispose();
    super.dispose();
  }

  void _initSeats() {
    final random = Random();
    seats = List.generate(10, (r) => List.generate(20, (c) {
      if (c == 9 || c == 10) return 0;
      if (random.nextDouble() < 0.15) return 2;
      return 1;
    }));
  }

  void _listenToBookedSeats() {
    final dateStr =
        '${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}';

    _seatSubscription = FirebaseFirestore.instance
        .collection('seatBookings')
        .where('cinemaName', isEqualTo: widget.cinemaName)
        .where('showTime', isEqualTo: widget.showTime)
        .where('date', isEqualTo: dateStr)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _bookedSeats = {};
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final seatId = data['seatId'] as String;
          final status = data['status'] as String;
          if (status == 'cancelled') continue;
          _bookedSeats[seatId] = data;

          final row = seatId[0].codeUnitAt(0) - 65;
          final col = int.parse(seatId.substring(1)) - 1;
          var actualCol = col;
          if (col >= 9) actualCol += 2;

          if (row >= 0 && row < 10 && actualCol >= 0 && actualCol < 20) {
            if (status == 'booked') {
              seats[row][actualCol] = 2;
            } else if (status == 'blocked') {
              seats[row][actualCol] = 4;
            }
          }
        }
      });
    });
  }

  void _tap(int r, int c) {
    if (seats[r][c] == 0 || seats[r][c] == 2 || seats[r][c] == 4) return;
    setState(() => seats[r][c] = seats[r][c] == 1 ? 3 : 1);

    // Animate bottom panel based on selection
    if (_hasSelectedSeats) {
      _panelSlideController.forward();
    } else {
      _panelSlideController.reverse();
    }
  }

  bool get _hasSelectedSeats {
    for (var row in seats) {
      if (row.contains(3)) return true;
    }
    return false;
  }

  int get _selectedSeatCount {
    int count = 0;
    for (var row in seats) {
      for (var s in row) {
        if (s == 3) count++;
      }
    }
    return count;
  }

  List<String> get _selectedSeatNames {
    List<String> selected = [];
    for (int r = 0; r < seats.length; r++) {
      for (int c = 0; c < seats[r].length; c++) {
        if (seats[r][c] == 3) {
          String rowLabel = String.fromCharCode(65 + r);
          int seatNum = 0;
          for (int i = 0; i <= c; i++) {
            if (seats[0][i] != 0) seatNum++;
          }
          selected.add('$rowLabel$seatNum');
        }
      }
    }
    return selected;
  }

  void _proceedToBooking() {
    final selectedSeats = _selectedSeatNames;
    for (final seat in selectedSeats) {
      if (_bookedSeats.containsKey(seat)) {
        final status = _bookedSeats[seat]['status'];
        if (status == 'booked' || status == 'blocked') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Seat $seat is already $status'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TicketScreen(
          selectedSeats: selectedSeats,
          movieName: widget.movieName,
          cinemaName: widget.cinemaName,
          showTime: widget.showTime,
          movieImageUrl: widget.movieImageUrl,
          selectedDate: widget.selectedDate,
          rating: widget.rating,
        ),
      ),
    );
  }

  String get _formattedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${widget.selectedDate.day} ${months[widget.selectedDate.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0E1A),
              Color(0xFF0A0A0F),
              Color(0xFF080810),
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Main scrollable content
            Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 56),
                // Cinema screen
                _buildCinemaScreen(),
                const SizedBox(height: 4),
                // "SCREEN" label
                Center(
                  child: Text(
                    'SCREEN',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 6,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Seat grid
                Expanded(child: _buildSeatGrid()),
                // Legend
                _buildLegend(),
                // Spacer for bottom panel
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _hasSelectedSeats ? 160 : 16,
                ),
              ],
            ),
            // Bottom booking panel
            if (_hasSelectedSeats) _buildBottomPanel(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        children: [
          Text(
            widget.movieName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${widget.cinemaName}  •  ${widget.showTime}  •  $_formattedDate',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE50914).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFD4AF37), size: 14),
                const SizedBox(width: 3),
                Text(
                  widget.rating,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCinemaScreen() {
    return ListenableBuilder(
      listenable: _screenGlowAnim,
      builder: (context, child) {
        return SizedBox(
          width: double.infinity,
          height: 70,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: CustomPaint(
              painter: CinemaScreenPainter(
                glowIntensity: _screenGlowAnim.value,
              ),
              size: Size.infinite,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSeatGrid() {
    return InteractiveViewer(
      constrained: false,
      minScale: 0.3,
      maxScale: 5,
      boundaryMargin: const EdgeInsets.all(80),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Column numbers
              _buildColumnNumbers(),
              const SizedBox(height: 6),
              // Seat rows
              ...List.generate(seats.length, (r) => _buildSeatRow(r)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColumnNumbers() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 32), // Space for row label
        ...List.generate(seats[0].length, (c) {
          if (seats[0][c] == 0) {
            return const SizedBox(width: 30);
          }
          int seatNum = 0;
          for (int i = 0; i <= c; i++) {
            if (seats[0][i] != 0) seatNum++;
          }
          return SizedBox(
            width: 30,
            child: Center(
              child: Text(
                seatNum.toString(),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.2),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSeatRow(int rowIndex) {
    final rowLabel = String.fromCharCode(65 + rowIndex);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row label
          SizedBox(
            width: 32,
            child: Center(
              child: Text(
                rowLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          // Seats
          ...List.generate(seats[rowIndex].length, (c) {
            return AnimatedSeatWidget(
              seatState: seats[rowIndex][c],
              onTap: () => _tap(rowIndex, c),
              rowIndex: rowIndex,
              colIndex: c,
              entranceDelay: Duration(milliseconds: 40 * rowIndex + 10 * (c % 5)),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return FadeTransition(
      opacity: _legendFadeAnim,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendItem(const Color(0xFF1E2535), const Color(0xFF2A3548), 'Available'),
            const SizedBox(width: 16),
            _legendItem(const Color(0xFFD4AF37), const Color(0xFFB8941E), 'Booked'),
            const SizedBox(width: 16),
            _legendItem(const Color(0xFFE50914), const Color(0xFFFF2D3A), 'Selected'),
            const SizedBox(width: 16),
            _legendItem(const Color(0xFF3A1015), const Color(0xFF4A1520), 'Blocked'),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color fill, Color border, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: border, width: 1),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel() {
    final seatNames = _selectedSeatNames;
    final count = _selectedSeatCount;
    final total = count * _pricePerSeat;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _panelSlideAnim,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF12141D),
                Color(0xFF0E1018),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Selected seats chips
                  SizedBox(
                    height: 32,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: seatNames.length,
                      itemBuilder: (context, index) {
                        return _buildSeatChip(seatNames[index], index);
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Price and book button row
                  Row(
                    children: [
                      // Price section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$count ${count == 1 ? 'Seat' : 'Seats'} Selected',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rs. ${total.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Book Now button
                      _buildBookButton(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeatChip(String seatName, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 200 + index * 50),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE50914), Color(0xFFC2060F)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE50914).withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_seat_rounded, color: Colors.white, size: 13),
            const SizedBox(width: 4),
            Text(
              seatName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _proceedToBooking,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE50914), Color(0xFFB8060F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE50914).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFFE50914).withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Book Now',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
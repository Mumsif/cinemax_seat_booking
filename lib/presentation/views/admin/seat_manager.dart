import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cinemax_seat_booking/core/services/admin_service.dart';
import 'package:cinemax_seat_booking/presentation/widgets/animated_seat_widget.dart';
import 'package:cinemax_seat_booking/presentation/widgets/cinema_screen_painter.dart';

class AdminSeatManagement extends StatefulWidget {
  final String? restrictedCinema; 

  const AdminSeatManagement({super.key, this.restrictedCinema});

  @override
  State<AdminSeatManagement> createState() => _AdminSeatManagementState();
}

class _AdminSeatManagementState extends State<AdminSeatManagement>
    with TickerProviderStateMixin {
  late String _selectedCinema;
  String _selectedShowTime = '06:30 PM';
  DateTime _selectedDate = DateTime.now();
  
  List<List<int>> _seats = [];
  Map<String, dynamic> _seatBookings = {};
  bool _isLoading = true;

  // Animation controllers
  late AnimationController _screenGlowController;
  late Animation<double> _screenGlowAnim;
  late AnimationController _legendController;
  late Animation<double> _legendFadeAnim;

  final List<String> _allCinemas = [
    'Archana Cinema',
    'GK Cinemax',
    'Shanthi Cinema',
    'PCA Cinemas',
  ];

  /// Determine if cinema admin using AdminService (more reliable than widget parameter)
  bool get _isCinemaAdmin {
    if (widget.restrictedCinema != null && 
        widget.restrictedCinema!.isNotEmpty && 
        widget.restrictedCinema != 'null' && 
        widget.restrictedCinema!.trim().isNotEmpty) {
      return true;
    }
    return AdminService.isCinemaAdmin;
  }

  /// Get the cinema name for this admin
  String? get _cinemaName {
    if (widget.restrictedCinema != null && 
        widget.restrictedCinema!.isNotEmpty && 
        widget.restrictedCinema != 'null' && 
        widget.restrictedCinema!.trim().isNotEmpty) {
      return widget.restrictedCinema;
    }
    if (AdminService.isCinemaAdmin) {
      return AdminService.adminCinema;
    }
    return null;
  }

  /// Get cinemas this admin can access
  List<String> get _availableCinemas {
    final cinema = _cinemaName;
    if (cinema != null && cinema.isNotEmpty) {
      return [cinema];
    }
    return _allCinemas;
  }

  @override
  void initState() {
    super.initState();
    _selectedCinema = _availableCinemas.first;
    
    _initSeats();
    _loadSeatBookings();
    _initAnimations();
  }

  void _initAnimations() {
    // Screen glow pulse
    _screenGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _screenGlowAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _screenGlowController, curve: Curves.easeInOut),
    );

    // Legend fade in
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
    _screenGlowController.dispose();
    _legendController.dispose();
    super.dispose();
  }

  void _initSeats() {
    _seats = List.generate(10, (r) => List.generate(20, (c) {
      if (c == 9 || c == 10) return 0;
      return 1;
    }));
  }

  Future<void> _loadSeatBookings() async {
    setState(() => _isLoading = true);
    try {
      final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      
      final snapshot = await FirebaseFirestore.instance
          .collection('seatBookings')
          .where('cinemaName', isEqualTo: _selectedCinema)
          .get();

      setState(() {
        _seatBookings = {};
        _initSeats();
        
        for (final doc in snapshot.docs) {
          final data = doc.data();
          
          if (data['showTime'] != _selectedShowTime) continue;
          if (data['date'] != dateStr) continue;
          
          final seatId = data['seatId'] as String;
          final status = data['status'] as String;
          
          if (status == 'cancelled') continue;
          
          _seatBookings[seatId] = data;
          
          final row = seatId[0].codeUnitAt(0) - 65;
          final col = int.parse(seatId.substring(1)) - 1;
          var actualCol = col;
          if (col >= 9) actualCol += 2;
          
          if (row >= 0 && row < 10 && actualCol >= 0 && actualCol < 20) {
            if (status == 'booked') {
              _seats[row][actualCol] = 2;
            } else if (status == 'blocked') {
              _seats[row][actualCol] = 4;
            }
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading bookings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _blockSeat(String seatId, int row, int col) async {
    final hasAccess = (widget.restrictedCinema == null || 
                       widget.restrictedCinema!.isEmpty || 
                       widget.restrictedCinema == 'null' ||
                       widget.restrictedCinema!.trim().isEmpty) ||
                      widget.restrictedCinema == _selectedCinema || 
                      AdminService.canAccessCinema(_selectedCinema);
                      
    if (!hasAccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access denied: You cannot manage this cinema'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    
    try {
      await FirebaseFirestore.instance
          .collection('seatBookings')
          .doc('${_selectedCinema}_${_selectedShowTime}_$seatId')
          .set({
            'seatId': seatId,
            'cinemaName': _selectedCinema,
            'showTime': _selectedShowTime,
            'date': dateStr,
            'status': 'blocked',
            'blockedBy': AdminService.adminEmail ?? 'unknown',
            'blockedAt': FieldValue.serverTimestamp(),
          });

      setState(() => _seats[row][col] = 4);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seat $seatId blocked successfully')),
      );
      _loadSeatBookings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error blocking seat: $e')),
      );
    }
  }

  Future<void> _unblockSeat(String seatId, int row, int col) async {
    try {
      await FirebaseFirestore.instance
          .collection('seatBookings')
          .doc('${_selectedCinema}_${_selectedShowTime}_$seatId')
          .delete();

      setState(() {
        _seats[row][col] = 1;
        _seatBookings.remove(seatId);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seat $seatId unblocked successfully')),
      );
      _loadSeatBookings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error unblocking seat: $e')),
      );
    }
  }

  Future<void> _cancelBooking(String seatId, String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12141D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFE50914)),
            SizedBox(width: 8),
            Text(
              'Cancel Booking',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel the booking $bookingId for seat $seatId?',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No', style: TextStyle(color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      
      final seatDocs = await FirebaseFirestore.instance
          .collection('seatBookings')
          .where('bookingId', isEqualTo: bookingId)
          .get();
        
      for (final doc in seatDocs.docs) {
        batch.update(doc.reference, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledBy': AdminService.adminEmail ?? 'unknown',
        });
      }
      
      batch.update(
        FirebaseFirestore.instance.collection('tickets').doc(bookingId),
        {'status': 'cancelled', 'cancelledAt': FieldValue.serverTimestamp()},
      );
      
      await batch.commit();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking $bookingId cancelled successfully')),
      );
      
      _loadSeatBookings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling booking: $e')),
      );
    }
  }

  void _showSeatActions(String seatId, int row, int col) {
    final booking = _seatBookings[seatId];
    final status = booking?['status'] ?? 'available';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
              color: Colors.white.withOpacity(0.06),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      'Seat $seatId',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildStatusBadge(status),
                  ],
                ),
                if (booking != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow(Icons.movie_rounded, 'Movie', booking['movieName'] ?? 'N/A'),
                        const SizedBox(height: 8),
                        _infoRow(Icons.receipt_rounded, 'Booking ID', booking['bookingId'] ?? 'N/A'),
                        if (booking['blockedBy'] != null) ...[
                          const SizedBox(height: 8),
                          _infoRow(Icons.admin_panel_settings_rounded, 'Blocked By', booking['blockedBy']),
                        ]
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                
                if (status == 'available' || status == 'cancelled')
                  _buildActionButton(
                    label: 'Block Seat',
                    icon: Icons.block,
                    color: const Color(0xFFE50914),
                    onTap: () {
                      Navigator.pop(context);
                      _blockSeat(seatId, row, col);
                    },
                  ),
                
                if (status == 'blocked')
                  _buildActionButton(
                    label: 'Unblock Seat',
                    icon: Icons.lock_open_rounded,
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      _unblockSeat(seatId, row, col);
                    },
                  ),
                
                if (status == 'booked')
                  _buildActionButton(
                    label: 'Cancel Booking',
                    icon: Icons.cancel_presentation_rounded,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      _cancelBooking(seatId, booking['bookingId']);
                    },
                  ),
                
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Close',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'booked':
        color = const Color(0xFFD4AF37);
        break;
      case 'blocked':
        color = const Color(0xFFE50914);
        break;
      default:
        color = Colors.green;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.3), size: 14),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _countSeats(int status) {
    int count = 0;
    for (var row in _seats) {
      for (var s in row) {
        if (s == status) count++;
      }
    }
    return count;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (_, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFE50914),
            onPrimary: Colors.white,
            surface: Color(0xFF12141D),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF12141D),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadSeatBookings();
    }
  }

  String _getSeatName(int rowIndex, int colIndex) {
    final rowLabel = String.fromCharCode(65 + rowIndex);
    int seatNum = 0;
    for (int i = 0; i <= colIndex; i++) {
      if (_seats[0][i] != 0) seatNum++;
    }
    return '$rowLabel$seatNum';
  }

  Widget _buildShowTimeDropdown() {
    return _customDropdown(
      icon: Icons.access_time_rounded,
      value: _selectedShowTime,
      items: const ['06:00 AM', '10:30 AM', '02:30 PM', '06:30 PM', '10:30 PM'],
      onChanged: (v) => setState(() => _selectedShowTime = v),
    );
  }

  Widget _buildCinemaDropdown() {
    return _customDropdown(
      icon: Icons.movie_filter_rounded,
      value: _selectedCinema,
      items: _availableCinemas,
      onChanged: (v) => setState(() => _selectedCinema = v),
    );
  }

  Widget _customDropdown({
    required IconData icon,
    required String value,
    required List<String> items,
    required Function(String) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE50914), size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                dropdownColor: const Color(0xFF12141D),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                icon: Icon(Icons.arrow_drop_down, color: Colors.white.withOpacity(0.3), size: 16),
                isExpanded: true,
                items: items.map((item) => DropdownMenuItem(
                  value: item,
                  child: Text(item),
                )).toList(),
                onChanged: (v) {
                  if (v != null) {
                    onChanged(v);
                    _loadSeatBookings();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, int count, Color bgColor, Color borderColor, Color textColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: borderColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: textColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
                Text(
                  label,
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
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
              ...List.generate(_seats.length, (r) => _buildSeatRow(r)),
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
        ...List.generate(_seats[0].length, (c) {
          if (_seats[0][c] == 0) {
            return const SizedBox(width: 30);
          }
          int seatNum = 0;
          for (int i = 0; i <= c; i++) {
            if (_seats[0][i] != 0) seatNum++;
          }
          return SizedBox(
            width: 30,
            child: Center(
              child: Text(
                seatNum.toString(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.2),
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
                  color: Colors.white.withOpacity(0.25),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          // Seats
          ...List.generate(_seats[rowIndex].length, (c) {
            final s = _seats[rowIndex][c];
            final seatName = _getSeatName(rowIndex, c);
            
            return AnimatedSeatWidget(
              seatState: s,
              onTap: s == 0 ? () {} : () => _showSeatActions(seatName, rowIndex, c),
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
            color: Colors.white.withOpacity(0.45),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCinemaAdmin = _isCinemaAdmin;
    final cinemaName = _cinemaName;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              isCinemaAdmin && cinemaName != null
                  ? '$cinemaName'
                  : 'Manage Seats',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}  •  $_selectedShowTime',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 18),
            ),
            onPressed: _loadSeatBookings,
          ),
        ],
      ),
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
            : Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).padding.top + 56),
                  
                  // Top filter controls card
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Date Picker button
                              Expanded(
                                child: GestureDetector(
                                  onTap: _selectDate,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today_rounded, color: Color(0xFFE50914), size: 14),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                        const Spacer(),
                                        Icon(Icons.arrow_drop_down, color: Colors.white.withOpacity(0.3), size: 16),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Show Time selector
                              Expanded(
                                child: _buildShowTimeDropdown(),
                              ),
                            ],
                          ),
                          if (!isCinemaAdmin) ...[
                            const SizedBox(height: 8),
                            // Cinema selector for super admin
                            _buildCinemaDropdown(),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Stats
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: _statCard('Available', _countSeats(1), const Color(0xFF1E2535), const Color(0xFF2A3548), Colors.white70, Icons.event_seat_rounded)),
                        const SizedBox(width: 8),
                        Expanded(child: _statCard('Booked', _countSeats(2), const Color(0xFFD4AF37), const Color(0xFFD4AF37), const Color(0xFFD4AF37), Icons.airplane_ticket_rounded)),
                        const SizedBox(width: 8),
                        Expanded(child: _statCard('Blocked', _countSeats(4), const Color(0xFFE50914), const Color(0xFFE50914), const Color(0xFFFF2D3A), Icons.block_flipped)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  
                  // Cinema screen curve
                  _buildCinemaScreen(),
                  const SizedBox(height: 4),
                  
                  // "SCREEN" label
                  Center(
                    child: Text(
                      'SCREEN',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.25),
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
                  const SizedBox(height: 16),
                ],
              ),
      ),
    );
  }
}
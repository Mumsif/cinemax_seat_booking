import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cinemax_seat_booking/core/services/admin_service.dart';

class AdminSeatManagement extends StatefulWidget {
  final String? restrictedCinema; 

  const AdminSeatManagement({super.key, this.restrictedCinema});

  @override
  State<AdminSeatManagement> createState() => _AdminSeatManagementState();
}

class _AdminSeatManagementState extends State<AdminSeatManagement> {
  late String _selectedCinema;
  String _selectedShowTime = '06:30 PM';
  DateTime _selectedDate = DateTime.now();
  
  List<List<int>> _seats = [];
  Map<String, dynamic> _seatBookings = {};
  bool _isLoading = true;

  final List<String> _allCinemas = [
    'Archana Cinema',
    'GK Cinemax',
    'Shanthi Cinema',
    'PCA Cinemas',
  ];

  /// Determine if cinema admin using AdminService (more reliable than widget parameter)
  bool get _isCinemaAdmin {
    // First check widget parameter
    if (widget.restrictedCinema != null && 
        widget.restrictedCinema!.isNotEmpty && 
        widget.restrictedCinema != 'null' && 
        widget.restrictedCinema!.trim().isNotEmpty) {
      return true;
    }
    // Fallback to AdminService cache
    return AdminService.isCinemaAdmin;
  }

  /// Get the cinema name for this admin
  String? get _cinemaName {
    // Priority 1: widget parameter
    if (widget.restrictedCinema != null && 
        widget.restrictedCinema!.isNotEmpty && 
        widget.restrictedCinema != 'null' && 
        widget.restrictedCinema!.trim().isNotEmpty) {
      return widget.restrictedCinema;
    }
    // Priority 2: AdminService cache
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
    print('DEBUG SeatManager init: widget.restrictedCinema=${widget.restrictedCinema}');
    print('DEBUG SeatManager init: _cinemaName=$_cinemaName');
    print('DEBUG SeatManager init: _isCinemaAdmin=$_isCinemaAdmin');
    print('DEBUG SeatManager init: _selectedCinema=$_selectedCinema');
    _initSeats();
    _loadSeatBookings();
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
      
      print('Loading seats for: $_selectedCinema | $_selectedShowTime | $dateStr');

      final snapshot = await FirebaseFirestore.instance
        .collection('seatBookings')
        .where('cinemaName', isEqualTo: _selectedCinema)
        .get();

      print('Found ${snapshot.docs.length} total bookings for $_selectedCinema');

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
            if (status == 'booked') _seats[row][actualCol] = 2;
            else if (status == 'blocked') _seats[row][actualCol] = 4;
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      print('ERROR loading seats: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
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
        SnackBar(content: Text('Seat $seatId blocked')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
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
        SnackBar(content: Text('Seat $seatId unblocked')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _cancelBooking(String seatId, String bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Cancel Booking', style: TextStyle(color: Colors.white)),
        content: Text('Cancel booking $bookingId?', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes', style: TextStyle(color: Colors.white)),
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
        SnackBar(content: Text('Booking $bookingId cancelled')),
      );
      
      _loadSeatBookings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showSeatActions(String seatId, int row, int col) {
    final booking = _seatBookings[seatId];
    final status = booking?['status'] ?? 'available';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seat $seatId',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Status: ${status.toUpperCase()}',
                style: TextStyle(
                  color: status == 'booked' 
                    ? Colors.yellow 
                    : status == 'blocked' 
                      ? Colors.red 
                      : Colors.green,
                  fontSize: 14,
                ),
              ),
              if (booking != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Movie: ${booking['movieName'] ?? 'N/A'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  'Booking: ${booking['bookingId'] ?? 'N/A'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),
              
              if (status == 'available' || status == 'cancelled')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _blockSeat(seatId, row, col);
                    },
                    icon: const Icon(Icons.block, size: 18),
                    label: const Text('Block Seat', style: TextStyle(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B0000),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              
              if (status == 'blocked')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _unblockSeat(seatId, row, col);
                    },
                    icon: const Icon(Icons.lock_open, size: 18),
                    label: const Text('Unblock Seat', style: TextStyle(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              
              if (status == 'booked')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _cancelBooking(seatId, booking['bookingId']);
                    },
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Cancel Booking', style: TextStyle(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _color(int s) => [
    Colors.transparent,
    Color(0xFF6B6565),
    Color(0xFFD4AF37),
    Color(0xFFC41E3A),
    Color(0xFF8B0000),
  ][s];

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final sp = w / 375;

    // CRITICAL FIX: Use _isCinemaAdmin getter which checks BOTH widget and AdminService
    final isCinemaAdmin = _isCinemaAdmin;
    final cinemaName = _cinemaName;

    print('DEBUG SeatManager build: widget.restrictedCinema=${widget.restrictedCinema}');
    print('DEBUG SeatManager build: _cinemaName=$cinemaName');
    print('DEBUG SeatManager build: _isCinemaAdmin=$isCinemaAdmin');

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text(
          isCinemaAdmin && cinemaName != null
            ? '$cinemaName - Seats' 
            : 'Manage Seats',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0F0F0F),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSeatBookings,
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
        : Column(
            children: [
              // Date picker
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16 * sp, vertical: 8 * sp),
                child: GestureDetector(
                  onTap: () async {
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
                            surface: Color(0xFF1E1E1E),
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                      _loadSeatBookings();
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14 * sp, vertical: 10 * sp),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE50914).withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today, color: Color(0xFFE50914), size: 18),
                        SizedBox(width: 8 * sp),
                        Text(
                          '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ),
              
              // CRITICAL FIX: Cinema selector ONLY for super admin
              // Use the local isCinemaAdmin variable, NOT widget.restrictedCinema directly
              if (!isCinemaAdmin)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16 * sp),
                  child: _filterDropdown(
                    'Cinema',
                    _selectedCinema,
                    _availableCinemas,
                    (v) => setState(() => _selectedCinema = v),
                  ),
                ),
              
              // Show time selector
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16 * sp),
                child: _filterDropdown(
                  'Show Time',
                  _selectedShowTime,
                  ['06:00 AM', '10:30 AM', '02:30 PM', '06:30 PM', '10:30 PM'],
                  (v) => setState(() => _selectedShowTime = v),
                ),
              ),
              
              // Stats
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16 * sp),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statCard('Available', _countSeats(1), Colors.grey),
                    _statCard('Booked', _countSeats(2), Colors.yellow),
                    _statCard('Blocked', _countSeats(4), Colors.red),
                  ],
                ),
              ),
              
              SizedBox(height: 20 * sp),
              
              // Seat Grid
              Expanded(
                child: InteractiveViewer(
                  constrained: false,
                  minScale: 0.3,
                  maxScale: 5,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 30),
                              ...List.generate(_seats[0].length, (c) {
                                if (_seats[0][c] == 0) {
                                  return Container(width: 22, margin: const EdgeInsets.symmetric(horizontal: 3));
                                }
                                int seatNum = 0;
                                for (int i = 0; i <= c; i++) {
                                  if (_seats[0][i] != 0) seatNum++;
                                }
                                return Container(
                                  width: 22,
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  alignment: Alignment.center,
                                  child: Text(
                                    seatNum.toString(),
                                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        ...List.generate(
                          _seats.length,
                          (r) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 30,
                                  child: Text(
                                    String.fromCharCode(65 + r),
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                ),
                                ...List.generate(_seats[r].length, (c) {
                                  final s = _seats[r][c];
                                  final seatName = '${String.fromCharCode(65 + r)}${c < 9 ? c + 1 : c - 1}';
                                  return GestureDetector(
                                    onTap: s == 0 ? null : () => _showSeatActions(seatName, r, c),
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                      decoration: BoxDecoration(
                                        color: _color(s),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Legend
              Padding(
                padding: EdgeInsets.all(16 * sp),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _legend(Color(0xFF6B6565), "Available"),
                    const SizedBox(width: 20),
                    _legend(Color(0xFFD4AF37), "Booked"),
                    const SizedBox(width: 20),
                    _legend(Color(0xFF8B0000), "Blocked"),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Widget _filterDropdown(String label, String value, List<String> items, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: const Color(0xFF1E1E1E),
              style: const TextStyle(color: Colors.white),
              isExpanded: true,
              items: items.map((item) => DropdownMenuItem(
                value: item,
                child: Text(item, style: const TextStyle(fontSize: 13)),
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
    );
  }

  Widget _statCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
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

  Widget _legend(Color c, String t) => Row(
    children: [
      Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 6),
      Text(t, style: const TextStyle(color: Colors.white70, fontSize: 12)),
    ],
  );
}
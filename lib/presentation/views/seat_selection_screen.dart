import 'dart:async';
import 'dart:math';
import 'package:cinemax_seat_booking/core/theme/app_theme.dart';
import 'package:cinemax_seat_booking/presentation/views/ticket_screen.dart';
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

class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  // 0=aisle, 1=available(grey), 2=booked(yellow), 3=selected(red), 4=blocked(dark red)
  late List<List<int>> seats;
  Map<String, dynamic> _bookedSeats = {};
  StreamSubscription? _seatSubscription;

  @override
  void initState() {
    super.initState();
    _initSeats();
    _listenToBookedSeats();
  }

  @override
  void dispose() {
    _seatSubscription?.cancel();
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
    final dateStr = '${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2, '0')}-${widget.selectedDate.day.toString().padLeft(2, '0')}';

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
              if (status == 'booked') seats[row][actualCol] = 2;
              else if (status == 'blocked') seats[row][actualCol] = 4;
            }
          }
        });
      });
  }

  void _tap(int r, int c) {
    if (seats[r][c] == 0 || seats[r][c] == 2 || seats[r][c] == 4) return;
    setState(() => seats[r][c] = seats[r][c] == 1 ? 3 : 1);
  }

  bool get _hasSelectedSeats {
    for (var row in seats) { if (row.contains(3)) return true; }
    return false;
  }

  List<String> get _selectedSeatNames {
    List<String> selected = [];
    for (int r = 0; r < seats.length; r++) {
      for (int c = 0; c < seats[r].length; c++) {
        if (seats[r][c] == 3) {
          String rowLabel = String.fromCharCode(65 + r);
          int seatNum = 0;
          for (int i = 0; i <= c; i++) { if (seats[0][i] != 0) seatNum++; }
          selected.add('$rowLabel$seatNum');
        }
      }
    }
    return selected;
  }

  Color _color(int s) => [Colors.transparent, Color(0xFF6B6565), Color(0xFFD4AF37), Color(0xFFC41E3A), Color(0xFF8B0000)][s];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Select Seats You Want to Book", style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: const Color(0xFF0F0F0F),
        centerTitle: true,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _hasSelectedSeats ? () {
              final selectedSeats = _selectedSeatNames;
              for (final seat in selectedSeats) {
                if (_bookedSeats.containsKey(seat)) {
                  final status = _bookedSeats[seat]['status'];
                  if (status == 'booked' || status == 'blocked') {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Seat $seat is already $status'), backgroundColor: Colors.red));
                    return;
                  }
                }
              }
              Navigator.push(context, MaterialPageRoute(builder: (_) => TicketScreen(
                selectedSeats: selectedSeats,
                movieName: widget.movieName,
                cinemaName: widget.cinemaName,
                showTime: widget.showTime,
                movieImageUrl: widget.movieImageUrl,
                selectedDate: widget.selectedDate,
                rating: widget.rating,
              )));
            } : null,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.seatSelected, disabledBackgroundColor: Colors.grey.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
            child: Text("Book Seats", style: TextStyle(color: _hasSelectedSeats ? Colors.white : Colors.white54, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Column(children: [
        Container(width: 280, height: 6, margin: const EdgeInsets.symmetric(vertical: 20), decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(3))),
        Expanded(
          child: InteractiveViewer(
            constrained: false, minScale: 0.3, maxScale: 5, boundaryMargin: const EdgeInsets.all(100),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(width: 30),
                    ...List.generate(seats[0].length, (c) {
                      if (seats[0][c] == 0) return Container(width: 22, margin: const EdgeInsets.symmetric(horizontal: 3));
                      int seatNum = 0;
                      for (int i = 0; i <= c; i++) { if (seats[0][i] != 0) seatNum++; }
                      return Container(width: 22, margin: const EdgeInsets.symmetric(horizontal: 3), alignment: Alignment.center, child: Text(seatNum.toString(), style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)));
                    }),
                  ]),
                ),
                ...List.generate(seats.length, (r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 30, child: Text(String.fromCharCode(65 + r), style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold))),
                    ...List.generate(seats[r].length, (c) {
                      final s = seats[r][c];
                      return GestureDetector(
                        onTap: () => _tap(r, c),
                        child: Container(width: 22, height: 22, margin: const EdgeInsets.symmetric(horizontal: 3), decoration: BoxDecoration(color: _color(s), borderRadius: BorderRadius.circular(6))),
                      );
                    }),
                  ]),
                )),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _legend(AppTheme.seatAvailable, "Available"),
            const SizedBox(width: 20),
            _legend(AppTheme.seatPremium, "Booked"),
            const SizedBox(width: 20),
            _legend(AppTheme.seatSelected, "Selected"),
            const SizedBox(width: 20),
            _legend(Color(0xFF8B0000), "Blocked"),
          ]),
        ),
      ]),
    );
  }

  Widget _legend(Color c, String t) => Row(children: [
    Container(width: 16, height: 16, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
    const SizedBox(width: 6),
    Text(t, style: const TextStyle(color: Colors.white70, fontSize: 12)),
  ]);
}